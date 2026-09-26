import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/pending/pending_api.dart';
import 'package:hrhb_frontend/data/pending/pending_models.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/utils/korean.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 연속 답변 시트
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showStreakSheet(BuildContext context, {StreakSummary? streak}) async {
  final data = streak ?? await PendingApi.instance.fetchStreak();
  if (!context.mounted) return;
  await showHaruSheet<void>(
    context,
    style: HaruSheetStyle.streak,
    builder: (ctx) => _StreakSheet(streak: data),
  );
}

/// After saving an answer: the first answer of today celebrates the streak
/// (prototype: sheet after 420ms), otherwise a toast.
Future<void> afterAnswerSaved(
  BuildContext context, {
  required bool firstAnswer,
  required bool isToday,
}) async {
  if (firstAnswer && isToday) {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!context.mounted) return;
    await showStreakSheet(context);
  } else {
    HaruToast.show(context, '답변을 저장했어요');
  }
}

class _StreakSheet extends StatelessWidget {
  const _StreakSheet({required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    final n = streak.current;
    final today = dateOnly(DateTime.now());
    final tip = streak.answeredToday
        ? '오늘도 답했어요. 내일 새벽 3시에 새 질문이 도착해요.'
        : '오늘의 질문에 답하면 ${n + 1}일째가 돼요.';
    return Column(
      children: [
        const SizedBox(height: 26), // 18 gap + 8 margin-top
        _PopIn(
          delay: const Duration(milliseconds: 120),
          duration: const Duration(milliseconds: 550),
          child: const _Flicker(
            child: _FlameTile(),
          ),
        ),
        const SizedBox(height: 18),
        _PopIn(
          delay: const Duration(milliseconds: 250),
          child: Text(
            '$n',
            style: haruText(48, weight: FontWeight.w800, letterSpacing: -1.5, height: 1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$n일째 하루한번을 이어가고 있어요',
          style: haruText(15, color: HaruColors.inkSecondary),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      _PopIn(
                        delay: Duration(milliseconds: 300 + i * 60),
                        duration: const Duration(milliseconds: 420),
                        child: _WeekDot(
                          size: 34,
                          done: i < streak.week.length && streak.week[i].answered,
                          isToday: i < streak.week.length &&
                              sameDay(streak.week[i].date, today),
                          showCheck: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(weekdayShort[i], style: haruText(12, color: HaruColors.inkSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: HaruColors.canvas,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.sprout, size: 20, color: HaruColors.house),
              const SizedBox(width: 10),
              Expanded(child: Text(tip, style: haruText(14, height: 1.5))),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Pressable(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HaruColors.ink,
              borderRadius: BorderRadius.circular(HaruRadius.full),
            ),
            child: Text(
              '돌아가기',
              style: haruText(16, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlameTile extends StatelessWidget {
  const _FlameTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: HaruColors.streakTile,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(LucideIcons.flame, size: 40, color: HaruColors.streak),
    );
  }
}

/// Streak day circle — done: orange with a check, today (not done): orange ring.
class _WeekDot extends StatelessWidget {
  const _WeekDot({
    required this.size,
    required this.done,
    required this.isToday,
    this.showCheck = false,
  });

  final double size;
  final bool done;
  final bool isToday;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: done ? HaruColors.streak : HaruColors.streakTrack,
        shape: BoxShape.circle,
        border: isToday && !done
            ? Border.all(color: HaruColors.streak, width: 2)
            : null,
      ),
      child: done && showCheck
          ? const Icon(LucideIcons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}

/// Small version used on the home mini card (14px).
class StreakWeekDots extends StatelessWidget {
  const StreakWeekDots({super.key, required this.streak});

  final StreakSummary streak;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < streak.week.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          _PopIn(
            delay: Duration(milliseconds: 300 + i * 60),
            duration: const Duration(milliseconds: 400),
            child: _WeekDot(
              size: 14,
              done: streak.week[i].answered,
              isToday: sameDay(streak.week[i].date, today),
            ),
          ),
        ],
      ],
    );
  }
}

/// hxPop: scale .6 → 1.06 → 1 with fade.
class _PopIn extends StatelessWidget {
  const _PopIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMicroseconds / total.inMicroseconds, 1),
      builder: (_, t, c) {
        // 0→70%: .6→1.06, 70→100%: 1.06→1
        final s = t < 0.7 ? 0.6 + (1.06 - 0.6) * (t / 0.7) : 1.06 - 0.06 * ((t - 0.7) / 0.3);
        return Opacity(
          opacity: (t / 0.7).clamp(0, 1),
          child: Transform.scale(scale: s, child: c),
        );
      },
      child: child,
    );
  }
}

/// hxFlicker: scale 1 ↔ 1.08 and rotate 0 ↔ -4deg, 1.6s, after .8s.
class _Flicker extends StatefulWidget {
  const _Flicker({required this.child});
  final Widget child;

  @override
  State<_Flicker> createState() => _FlickerState();
}

class _FlickerState extends State<_Flicker> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _c.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final k = math.sin(_c.value * math.pi); // 0 → 1 → 0
        return Transform.rotate(
          angle: -4 * math.pi / 180 * k,
          child: Transform.scale(scale: 1 + 0.08 * k, child: child),
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 연·월 선택 시트
// ─────────────────────────────────────────────────────────────────────────────

/// Returns (year, month) or null.
Future<(int, int)?> showYearMonthSheet(
  BuildContext context, {
  required int year,
  required int month,
}) {
  return showHaruSheet<(int, int)>(
    context,
    style: HaruSheetStyle.yearMonth,
    builder: (_) => _YearMonthSheet(year: year, month: month),
  );
}

class _YearMonthSheet extends StatefulWidget {
  const _YearMonthSheet({required this.year, required this.month});
  final int year;
  final int month;

  @override
  State<_YearMonthSheet> createState() => _YearMonthSheetState();
}

class _YearMonthSheetState extends State<_YearMonthSheet> {
  late int _y = widget.year;
  late int _m = widget.month;
  final _now = DateTime.now();

  bool _disabled(int m) => _y > _now.year || (_y == _now.year && m > _now.month);

  @override
  Widget build(BuildContext context) {
    final nextDisabled = _y >= _now.year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12), // 16 gap - 4 handle margin
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HaruIconButton(
              icon: LucideIcons.chevronLeft,
              label: '이전 해',
              iconSize: 20,
              color: HaruColors.ink,
              pressScale: 0.95,
              onPressed: () => setState(() => _y--),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              child: Text(
                '$_y년',
                textAlign: TextAlign.center,
                style: haruText(19, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: nextDisabled ? 0.35 : 1,
              child: HaruIconButton(
                icon: LucideIcons.chevronRight,
                label: '다음 해',
                iconSize: 20,
                color: HaruColors.ink,
                pressScale: 0.95,
                onPressed: nextDisabled
                    ? null
                    : () => setState(() {
                          _y = math.min(_now.year, _y + 1);
                          if (_y == _now.year && _m > _now.month) _m = _now.month;
                        }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 78 / 36,
          children: [
            for (var m = 1; m <= 12; m++)
              Opacity(
                opacity: _disabled(m) ? 0.5 : 1,
                child: Pressable(
                  onTap: _disabled(m) ? null : () => setState(() => _m = m),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _m == m ? HaruColors.house : Colors.white,
                      borderRadius: BorderRadius.circular(HaruRadius.full),
                      border: Border.all(
                        color: _m == m ? HaruColors.house : HaruColors.inkLineSoft,
                      ),
                    ),
                    child: Text(
                      '$m월',
                      style: haruText(
                        14,
                        weight: _m == m ? FontWeight.w600 : FontWeight.w400,
                        color: _m == m ? Colors.white : HaruColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        HaruButton(
          label: '확인',
          size: HaruButtonSize.lg,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop((_y, _m)),
        ),
      ],
    );
  }
}
