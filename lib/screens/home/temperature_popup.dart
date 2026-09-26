import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';

/// 온도 상승 / 하강 팝업 (once a day, gated in HomeShell).
Future<void> showTemperaturePopup(BuildContext context, {required double delta}) {
  return showHaruModal<void>(
    context,
    padding: const EdgeInsets.all(28),
    builder: (ctx) => _TemperaturePopup(delta: delta),
  );
}

class _TemperaturePopup extends StatelessWidget {
  const _TemperaturePopup({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final rise = delta >= 0;
    final abs = delta.abs().toStringAsFixed(1);
    final band = rise ? HaruColors.accentPink : HaruColors.accentSky;
    final color = rise ? HaruColors.accentOrangeDeep : HaruColors.accentPurpleDeep;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HaruColors.surface,
        borderRadius: BorderRadius.circular(HaruRadius.xl),
        boxShadow: HaruShadows.s2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 148,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: band)),
                Center(
                  child: _Bob(
                    child: Icon(
                      rise ? LucideIcons.thermometerSun : LucideIcons.cloudRain,
                      size: 56,
                      color: HaruColors.dsInkSecondary,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: HaruIconButton(
                    icon: LucideIcons.x,
                    label: '닫기',
                    size: 36,
                    variant: HaruIconButtonVariant.onNight,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('어제보다', style: haruText(14, color: HaruColors.dsInkMuted)),
                const SizedBox(height: 4),
                Text(
                  rise ? '$abs°C 올랐어요' : '$abs°C 내렸어요',
                  style: haruText(28, weight: FontWeight.w700, letterSpacing: -0.6, color: HaruColors.dsInk),
                ),
                const SizedBox(height: 4),
                Text(
                  rise ? '가족의 온도가 조금 따뜻해졌어요' : '가족의 온도가 조금 식었어요',
                  style: haruText(15, color: HaruColors.dsInkSecondary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: HaruColors.canvasSoft,
                    borderRadius: BorderRadius.circular(HaruRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 변화',
                              style: haruText(14, weight: FontWeight.w600, color: HaruColors.dsInk),
                            ),
                            Text('어제 대비', style: haruText(12, color: HaruColors.dsInkFaint)),
                          ],
                        ),
                      ),
                      Text(
                        '${rise ? '+' : '−'}$abs°C',
                        style: haruText(24, weight: FontWeight.w700, color: color),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        rise ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                        size: 20,
                        color: color,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('오늘도 따뜻한 하루 보내세요', style: haruText(14, color: HaruColors.dsInkMuted)),
                const SizedBox(height: 16),
                HaruButton(
                  label: '확인',
                  size: HaruButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// hxBob: translateY 0 ↔ -6px, 2.4s ease-in-out, after .4s.
class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _c.repeat(reverse: true);
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
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}
