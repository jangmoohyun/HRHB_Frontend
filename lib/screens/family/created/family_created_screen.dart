import 'package:flutter/material.dart';

import 'package:hrhb_frontend/widgets/sprout_icon.dart';
import 'package:flutter/services.dart';

import '../../home/home_shell.dart';

const _cream = Color(0xFFFDFBF0);
const _titleGreen = Color(0xFF3A6A3F);
const _bodyGrey = Color(0xFF5F5F5F);
const _mutedGrey = Color(0xFF8F8F8F);
const _mint = Color(0xFF57C17D);
const _softMint = Color(0xFFE8F5E6);
const _tipBg = Color(0xFFF4F6E8);
const _guideBg = Color(0xFFF3F7EF);
const _buttonGreen = Color(0xFF3CB371);

class FamilyCreatedScreen extends StatelessWidget {
  const FamilyCreatedScreen({
    super.key,
    required this.familyCode,
    this.familyName = '우리 가족',
  });

  final String familyCode;
  final String familyName;

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: familyCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('가족 코드가 복사되었어요.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;

    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _BranchDecorations(screenSize: size)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    shortest * 0.05,
                    size.height * 0.008,
                    shortest * 0.08,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        foregroundColor: _mint,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
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
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      shortest * 0.07,
                      0,
                      shortest * 0.07,
                      size.height * 0.016,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.008),
                        const SproutIcon(size: 16),
                        SizedBox(height: size.height * 0.008),
                        Text(
                          '가족이\n생성되었어요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cafe24Oneprettynight',
                            fontSize: shortest * 0.068,
                            height: 1.2,
                            color: _titleGreen,
                          ),
                        ),
                        SizedBox(height: size.height * 0.008),
                        Text(
                          '가족 코드를 가족 구성원에게 공유해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: shortest * 0.033,
                            color: _mutedGrey,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: size.height * 0.016),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              shortest * 0.05,
                              size.height * 0.016,
                              shortest * 0.05,
                              size.height * 0.016,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x16000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const _FamilyBadge(),
                                SizedBox(height: size.height * 0.01),
                                const Text(
                                  '우리 가족 코드',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _bodyGrey,
                                  ),
                                ),
                                SizedBox(height: size.height * 0.012),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FBF6),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _mint,
                                      width: 1.6,
                                      strokeAlign: BorderSide.strokeAlignInside,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 56,
                                        ),
                                        child: Text(
                                          familyCode,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: shortest * 0.085,
                                            fontWeight: FontWeight.w800,
                                            color: _titleGreen,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        child: Transform.translate(
                                          offset: const Offset(0, 6),
                                          child: GestureDetector(
                                            onTap: () => _copyCode(context),
                                            child: const Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.copy_rounded,
                                                  color: _mutedGrey,
                                                  size: 22,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '복사하기',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _mutedGrey,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: size.height * 0.02),
                                Text(
                                  '이 코드를 가족 구성원에게 공유하면\n하루 한번 가족의 일원이 될 수 있어요!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: shortest * 0.031,
                                    height: 1.35,
                                    color: _bodyGrey,
                                  ),
                                ),
                                SizedBox(height: size.height * 0.02),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: size.height * 0.018,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _guideBg,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        const Row(
                                          children: [
                                            SproutIcon(size: 13),
                                            SizedBox(width: 6),
                                            Text(
                                              '참여 방법',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: _titleGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const _GuideStep(
                                          number: '1',
                                          text:
                                              '가족 구성원에게 위 코드를 공유해주세요.',
                                        ),
                                        const _GuideStep(
                                          number: '2',
                                          text:
                                              "가족 구성원이 '가족 참여하기'에서 코드를 입력하면",
                                        ),
                                        const _GuideStep(
                                          number: '3',
                                          text:
                                              '가족으로 함께 하루 한번을 시작할 수 있어요!',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: size.height * 0.01),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _tipBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Tip  여러 명이 함께 기록할수록 더 따뜻한 가족 커뮤니티가 만들어져요!',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: _bodyGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(height: size.height * 0.014),
                                SizedBox(
                                  width: double.infinity,
                                  height: size.height * 0.052,
                                  child: FilledButton(
                                    onPressed: () {
                                      Navigator.of(context).pushAndRemoveUntil(
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _FamilyBadge extends StatelessWidget {
  const _FamilyBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/background/leftbranch_2.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: _softMint,
            shape: BoxShape.circle,
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 8,
                child: Icon(Icons.favorite_rounded, size: 12, color: _mint),
              ),
              Icon(Icons.groups_rounded, size: 30, color: _mint),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Transform.flip(
          flipX: true,
          child: Image.asset(
            'assets/images/background/leftbranch_2.png',
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _mint,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _bodyGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
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
            asset: 'assets/images/background/leftbranch_3.png',
            top: h * 0.55,
            height: h * 0.28,
            angle: 0.2,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_1.png',
            top: h * 0.08,
            height: h * 0.28,
            angle: 0.1,
          ),
          rightBranch(
            asset: 'assets/images/background/rightbranch_3.png',
            top: h * 0.62,
            height: h * 0.28,
            angle: -0.15,
          ),
        ],
      ),
    );
  }
}

