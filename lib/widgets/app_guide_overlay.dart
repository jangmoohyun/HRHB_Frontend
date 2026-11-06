import 'package:flutter/material.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF8A8A8A);
const _buttonGreen = Color(0xFF3CB371);

class AppGuideStep {
  const AppGuideStep({
    required this.title,
    required this.body,
    this.targetKey,
    this.tabIndex,
    this.holePadding = 10,
    this.holeRadius = 18,
  });

  final String title;
  final String body;
  final GlobalKey? targetKey;

  /// 해당 단계로 들어갈 때 전환할 홈 탭 (null이면 유지).
  final int? tabIndex;
  final double holePadding;
  final double holeRadius;
}

/// 첫 실행 앱 가이드 — 하단 탭을 따라가며 하이라이트 + 설명.
class AppGuideOverlay extends StatefulWidget {
  const AppGuideOverlay({
    super.key,
    required this.steps,
    required this.onSelectTab,
    required this.onFinished,
  });

  final List<AppGuideStep> steps;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onFinished;

  @override
  State<AppGuideOverlay> createState() => _AppGuideOverlayState();
}

class _AppGuideOverlayState extends State<AppGuideOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Rect? _hole;
  late final AnimationController _pulse;

  AppGuideStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareStep(0));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _prepareStep(int i) async {
    final step = widget.steps[i];
    if (step.tabIndex != null) {
      widget.onSelectTab(step.tabIndex!);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    if (!mounted) return;
    setState(() {
      _index = i;
      _hole = _rectFor(step.targetKey, pad: step.holePadding);
    });
  }

  Rect? _rectFor(GlobalKey? key, {required double pad}) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx - pad,
      offset.dy - pad,
      box.size.width + pad * 2,
      box.size.height + pad * 2,
    ).inflate(0);
  }

  Future<void> _next() async {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
      return;
    }
    await _prepareStep(_index + 1);
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hole = _hole;
    // 하단 탭을 가리킬 때는 설명 카드를 위쪽에 둔다.
    final tipTop = hole == null
        ? size.height * 0.26
        : (hole.center.dy > size.height * 0.5
            ? size.height * 0.12
            : hole.bottom + 16);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _SpotlightPainter(
                  hole: hole,
                  radius: _step.holeRadius,
                ),
              ),
            ),
          ),
          if (hole != null)
            Positioned.fromRect(
              rect: hole.inflate(4),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(_step.holeRadius + 4),
                        border: Border.all(
                          color: Color.lerp(
                            const Color(0xFF7FA87A),
                            const Color(0xFF3CB371),
                            t,
                          )!,
                          width: 2.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3CB371)
                                .withValues(alpha: 0.18 + 0.18 * t),
                            blurRadius: 10 + 8 * t,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (hole != null)
            Positioned.fromRect(
              rect: hole,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (_step.tabIndex != null) {
                    widget.onSelectTab(_step.tabIndex!);
                  }
                  await _next();
                },
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            top: tipTop.clamp(24.0, size.height - 240),
            child: _GuideCard(
              stepIndex: _index,
              stepCount: widget.steps.length,
              title: _step.title,
              body: _step.body,
              isLast: _index >= widget.steps.length - 1,
              onNext: _next,
              onSkip: _skip,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.stepIndex,
    required this.stepCount,
    required this.title,
    required this.body,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final int stepIndex;
  final int stepCount;
  final String title;
  final String body;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD7E3D0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${stepIndex + 1}/$stepCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _titleGreen,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isLast)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: _mutedGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('건너뛰기'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cafe24Oneprettynight',
                fontSize: 20,
                color: _titleGreen,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: _bodyGrey,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: _buttonGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isLast ? '시작하기' : '다음',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (!isLast) ...[
              const SizedBox(height: 6),
              const Text(
                '빛나는 부분을 눌러도 다음으로 넘어가요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _mutedGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.radius});

  final Rect? hole;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (hole != null) {
      final cut = Path()
        ..addRRect(
          RRect.fromRectAndRadius(hole!, Radius.circular(radius)),
        );
      final dimmed = Path.combine(PathOperation.difference, overlay, cut);
      canvas.drawPath(
        dimmed,
        Paint()..color = const Color(0xCC1E2A1C),
      );
    } else {
      canvas.drawPath(
        overlay,
        Paint()..color = const Color(0xCC1E2A1C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole || oldDelegate.radius != radius;
  }
}
