import 'package:flutter/material.dart';

/// Shared branch background used on auth screens (login / email flow).
class AuthBranchBackground extends StatelessWidget {
  const AuthBranchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;

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
