import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_basics.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';

/// 22 가족 온도 상세 (시안 A).
class TemperatureScreen extends StatefulWidget {
  const TemperatureScreen({super.key});

  @override
  State<TemperatureScreen> createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen> {
  FamilyTemperatureResult? _t;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final t = await AuthedCall.run(ApiClient().fetchFamilyTemperature);
      if (mounted) setState(() => _t = t);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _info() => showHaruConfirm(
        context,
        title: '가족 온도란?',
        body: '가족이 질문에 답하고 따뜻한 말을 나눌수록 온도가 올라가요.\n'
            '매일 새벽 2시 50분에 전날 참여율·답변 길이·사진 첨부를 보고 -1.0°C ~ +1.0°C 사이로 변화해요.',
        confirmLabel: '확인',
        showCancel: false,
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
              child: Row(
                children: [
                  HaruIconButton(
                    icon: LucideIcons.chevronLeft,
                    label: '뒤로',
                    iconSize: 24,
                    color: HaruColors.ink,
                    pressScale: 0.95,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가족 온도',
                          style: haruText(26, weight: FontWeight.w700, letterSpacing: -0.6, color: HaruColors.dsInk),
                        ),
                        const SizedBox(height: 2),
                        Text('가족 간의 따뜻한 마음 온도예요', style: haruText(14, color: HaruColors.dsInkMuted)),
                      ],
                    ),
                  ),
                  HaruIconButton(icon: LucideIcons.info, label: '가족 온도란?', onPressed: _info),
                ],
              ),
            ),
            Expanded(
              child: _error
                  ? HaruErrorState(onRetry: _load)
                  : t == null
                      ? const Center(child: CircularProgressIndicator(color: HaruColors.primary))
                      : RefreshIndicator(
                          color: HaruColors.primary,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, kTabBarClearance),
                            children: [
                              _gaugeCard(t),
                              const SizedBox(height: 12),
                              HaruOutlineCard(
                                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '최근 6일간의 변화',
                                            style: haruText(16, weight: FontWeight.w700, color: HaruColors.dsInk),
                                          ),
                                        ),
                                        Text('단위 °C', style: haruText(12, color: HaruColors.dsInkFaint)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TempBarChart(
                                      values: [for (final c in t.recentChanges) c.delta],
                                      labels: [for (final c in t.recentChanges) '${c.date.month}/${c.date.day}'],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              HaruOutlineCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: HaruColors.accentPink,
                                        borderRadius: BorderRadius.circular(HaruRadius.md),
                                      ),
                                      child: const Icon(LucideIcons.sprout, size: 20, color: HaruColors.dsInkSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '오늘의 질문에 답하면 가족 온도가 올라가요.',
                                            style: haruText(14, height: 1.45, color: HaruColors.dsInkSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Pressable(
                                            onTap: () => HomeShellScope.maybeOf(context)?.switchTo(HaruTab.home),
                                            child: Text(
                                              '답변하러 가기',
                                              style: haruText(14, weight: FontWeight.w500, color: HaruColors.primary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Widget _gaugeCard(FamilyTemperatureResult t) {
    final up = t.deltaFromYesterday >= 0;
    final color = up ? HaruColors.accentOrangeDeep : HaruColors.accentPurpleDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: HaruColors.surface,
        borderRadius: BorderRadius.circular(HaruRadius.xl),
        boxShadow: HaruShadows.s1,
      ),
      child: Column(
        children: [
          if (t.bubbleText.isNotEmpty) _Bubble(text: t.bubbleText),
          const SizedBox(height: 20),
          _SegmentGauge(value: t.temperature),
          Transform.translate(
            offset: const Offset(0, -6),
            child: SizedBox(
              width: 280,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0°', style: haruText(12, color: HaruColors.dsInkFaint)),
                  Text('100°', style: haruText(12, color: HaruColors.dsInkFaint)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (t.statusLabel.isNotEmpty) HaruBadge(t.statusLabel),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: '어제보다 ',
              style: haruText(15, color: HaruColors.dsInkSecondary),
              children: [
                TextSpan(
                  text: '${t.deltaFromYesterday.abs().toStringAsFixed(1)}°C',
                  style: haruText(15, weight: FontWeight.w700, color: color),
                ),
                TextSpan(text: up ? ' 올라갔어요' : ' 내려갔어요'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: -6,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 12, height: 12, color: HaruColors.accentButter),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: HaruColors.accentButter,
            borderRadius: BorderRadius.circular(HaruRadius.lg),
          ),
          child: Text(text, style: haruText(14, color: HaruColors.dsInkSecondary)),
        ),
      ],
    );
  }
}

/// 280×150 semicircle split into six sticker-colored bands (28° each, 2° gaps)
/// with a marker at `value`% and the value in the middle.
class _SegmentGauge extends StatelessWidget {
  const _SegmentGauge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    const r = 140.0, band = 110.0;
    final ang = (value.clamp(0, 100) / 100) * math.pi;
    final mx = 140 - band * math.cos(ang);
    final my = 140 - band * math.sin(ang);
    return SizedBox(
      width: 280,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 0,
            width: 280,
            height: 140,
            child: CustomPaint(painter: _SegmentPainter(radius: r)),
          ),
          Positioned(
            left: mx - 11,
            top: my - 11,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: HaruColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: HaruColors.primary, width: 4),
                boxShadow: HaruShadows.s2,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  style: haruText(54, weight: FontWeight.w700, letterSpacing: -1.875, height: 1, color: HaruColors.dsInk),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('°C', style: haruText(22, weight: FontWeight.w600, height: 1, color: HaruColors.dsInk)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({required this.radius});
  final double radius;

  static const _colors = [
    HaruColors.accentSky,
    HaruColors.accentTeal,
    HaruColors.accentGreen,
    HaruColors.accentButter,
    HaruColors.accentOrange,
    HaruColors.accentPink,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Ring from 57% of the radius to the edge (CSS radial mask 57%).
    final inner = radius * 0.57;
    final thickness = radius - inner;
    final mid = inner + thickness / 2;
    final rect = Rect.fromCircle(center: Offset(radius, radius), radius: mid);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    const deg = math.pi / 180;
    for (var i = 0; i < 6; i++) {
      // Each band 28° with a 2° gap; the last band fills to 180°.
      final start = math.pi + i * 30 * deg;
      final sweep = (i == 5 ? 30 : 28) * deg;
      paint.color = _colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter oldDelegate) => false;
}
