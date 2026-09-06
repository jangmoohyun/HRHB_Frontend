import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hrhb_frontend/services/token_storage.dart';
import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../../home/home_shell.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF4A4A4A);
const _mutedGrey = Color(0xFF7A7A7A);
const _welcomeBg = Color(0xCCFFF8E8);
const _buttonGreen = Color(0xFF2F8F4E);
const _dashBorder = Color(0xFFD7CBA8);

class FamilyJoinedScreen extends StatefulWidget {
  const FamilyJoinedScreen({
    super.key,
    required this.familyName,
    required this.familyCode,
    required this.role,
  });

  final String familyName;
  final String familyCode;
  final String role;

  @override
  State<FamilyJoinedScreen> createState() => _FamilyJoinedScreenState();
}

class _FamilyJoinedScreenState extends State<FamilyJoinedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  /// "김하루가족" / "김하루" → 표시용 이름 "김하루"
  String get _nameOnly {
    final name = widget.familyName.trim();
    if (name.endsWith('가족')) {
      return name.substring(0, name.length - 2).trim();
    }
    return name;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: _cream,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/family/familyjoin/grassground.png',
                  width: size.width,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned.fill(child: _BranchDecorations(screenSize: size)),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  shortest * 0.08,
                  size.height * 0.02,
                  shortest * 0.08,
                  size.height * 0.02,
                ),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.045),
                    Text(
                      '참여 완료!',
                      style: TextStyle(
                        fontFamily: 'Cafe24Oneprettynight',
                        fontSize: shortest * 0.09,
                        color: _titleGreen,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SproutIcon(size: 16),
                    SizedBox(height: size.height * 0.01),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: Image.asset(
                                'assets/images/family/familyjoin/family_letter.png',
                                fit: BoxFit.contain,
                                width: shortest * 0.92,
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.012),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontFamily: 'Cafe24Oneprettynight',
                                fontSize: shortest * 0.055,
                                height: 1.35,
                                color: _bodyGrey,
                              ),
                              children: [
                                TextSpan(
                                  text: _nameOnly,
                                  style: const TextStyle(color: _titleGreen),
                                ),
                                const TextSpan(text: ' 가족에 참여하였습니다!'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: size.height * 0.02),
                          const _WelcomeBox(),
                          SizedBox(height: size.height * 0.028),
                          SizedBox(
                            width: double.infinity,
                            height: size.height * 0.058,
                            child: FilledButton(
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                await TokenStorage().saveFamilyProfile(
                                  familyName: _nameOnly,
                                  familyCode: widget.familyCode,
                                  myRoleLabel: widget.role,
                                  isFamilyCreator: false,
                                );
                                if (!mounted) return;
                                navigator.pushAndRemoveUntil(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const HomeShell(),
                                  ),
                                  (_) => false,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: _buttonGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                '확인',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(height: size.height * 0.02),
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
}

class _WelcomeBox extends StatelessWidget {
  const _WelcomeBox();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedRRectPainter(
        color: _dashBorder,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _welcomeBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Text(
              '환영합니다! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _bodyGrey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '이제 우리 가족과 함께\n따뜻한 순간들을 만들어가요. 💚',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: _mutedGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      const dash = 5.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _BranchDecorations extends StatelessWidget {
  const _BranchDecorations({required this.screenSize});

  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final h = screenSize.height;

    Widget leftBranch({
      required String asset,
      required double top,
      required double height,
      double angle = 0,
      double opacity = 0.78,
    }) {
      return Positioned(
        top: top,
        left: 0,
        child: Transform.translate(
          offset: Offset(-height * 0.12, height * 0.08),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomLeft,
              child: Image.asset(asset, height: height, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    Widget rightBranch({
      required String asset,
      required double top,
      required double height,
      double angle = 0,
      double opacity = 0.78,
      double edgeNudge = 0.12,
    }) {
      return Positioned(
        top: top,
        right: 0,
        child: Transform.translate(
          offset: Offset(height * edgeNudge, height * 0.08),
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.bottomRight,
              child: Image.asset(asset, height: height, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          leftBranch(
            asset: 'assets/images/background/leftbranch_1.png',
            top: h * 0.02,
            height: h * 0.28,
            angle: 0.25,
          ),
          leftBranch(
            asset: 'assets/images/background/leftbranch_4.png',
            top: h * 0.44,
            height: h * 0.2,
            angle: 0.2,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_1.png',
            top: h * 0.1,
            height: h * 0.29,
            angle: 0.1,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_3.png',
            top: h * 0.52,
            height: h * 0.18,
            angle: -0.15,
          ),
        ],
      ),
    );
  }
}

