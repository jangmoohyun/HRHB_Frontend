import 'package:flutter/material.dart';

import 'package:hrhb_frontend/widgets/sprout_icon.dart';

import '../../login/login_screen.dart';
import '../create/family_create_screen.dart';
import '../join/family_join_screen.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _mutedGrey = Color(0xFF8F8F8F);
const _cardShadow = Color(0x1A8D8D8D);
const _mint = Color(0xFF57C17D);

class FamilySelectScreen extends StatelessWidget {
  const FamilySelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.22,
            bottom: size.height * 0.24,
            child: Align(
              alignment: const Alignment(0, 0.08),
              child: Image.asset(
                'assets/images/loginpage/letter/loginletter.png',
                width: size.width * 1.03,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(child: _BranchDecorations(screenSize: size)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.05,
                    size.height * 0.012,
                    shortest * 0.08,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _mint,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                      ),
                      label: const Text(
                        '뒤로',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: shortest * 0.08),
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.02),
                      Text(
                        '하루한번',
                        style: TextStyle(
                          fontFamily: 'Cafe24Oneprettynight',
                          fontSize: shortest * 0.105,
                          height: 1.05,
                          color: _titleGreen,
                        ),
                      ),
                      SizedBox(height: size.height * 0.012),
                      Text(
                        '가족을 잇는 감성 커뮤니케이션',
                        style: TextStyle(
                          fontSize: shortest * 0.035,
                          height: 1.3,
                          letterSpacing: -0.3,
                          color: _mutedGrey,
                        ),
                      ),
                      SizedBox(height: size.height * 0.02),
                      const SproutDivider(),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.08,
                    0,
                    shortest * 0.08,
                    size.height * 0.055,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FamilyActionCard(
                          height: size.height * 0.19,
                          gradient: const [
                            Color(0xFFD7EDD4),
                            Color(0xFFC4E7BE),
                          ],
                          icon: const _DocumentPlusIcon(),
                          label: '가족 생성하기',
                          labelColor: _mint,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FamilyCreateScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: shortest * 0.045),
                      Expanded(
                        child: _FamilyActionCard(
                          height: size.height * 0.19,
                          gradient: const [
                            Color(0xFF6CCF88),
                            Color(0xFF54BF76),
                          ],
                          icon: const _FamilyHeartIcon(),
                          label: '가족 참여하기',
                          labelColor: Colors.white,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FamilyJoinScreen(),
                              ),
                            );
                          },
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
    );
  }
}

class _FamilyActionCard extends StatelessWidget {
  const _FamilyActionCard({
    required this.height,
    required this.gradient,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  final double height;
  final List<Color> gradient;
  final Widget icon;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          boxShadow: const [
            BoxShadow(
              color: _cardShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(width: 86, height: 86, child: icon),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentPlusIcon extends StatelessWidget {
  const _DocumentPlusIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Center(
          child: Icon(
            Icons.description_rounded,
            size: 82,
            color: Colors.white,
          ),
        ),
        Positioned(
          right: 6,
          bottom: 10,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 21),
          ),
        ),
      ],
    );
  }
}

class _FamilyHeartIcon extends StatelessWidget {
  const _FamilyHeartIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: const [
        Positioned(
          top: 4,
          child: Icon(Icons.favorite_rounded, size: 26, color: Colors.white),
        ),
        Positioned(
          left: 7,
          top: 30,
          child: Icon(Icons.person_rounded, size: 42, color: Colors.white),
        ),
        Positioned(
          right: 7,
          top: 30,
          child: Icon(Icons.person_rounded, size: 42, color: Colors.white),
        ),
      ],
    );
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
            asset: 'assets/images/background/leftbranch_2.png',
            top: h * 0.28,
            height: h * 0.24,
            angle: -0.05,
          ),
          leftBranch(
            asset: 'assets/images/background/leftbranch_3.png',
            top: h * 0.45,
            height: h * 0.29,
            angle: 0.2,
          ),
          leftBranch(
            asset: 'assets/images/background/leftbranch_4.png',
            top: h * 0.74,
            height: h * 0.24,
            angle: 0.2,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_1.png',
            top: h * 0.1,
            height: h * 0.29,
            angle: 0.1,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_2.png',
            top: h * 0.42,
            height: h * 0.24,
            angle: -0.05,
            edgeNudge: 0.28,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_3.png',
            top: h * 0.64,
            height: h * 0.3,
            angle: -0.15,
          ),
        ],
      ),
    );
  }
}

