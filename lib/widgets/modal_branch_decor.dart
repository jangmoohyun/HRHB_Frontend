import 'package:flutter/material.dart';

/// Soft corner branch decorations for family/profile modals.
class ModalBranchDecor extends StatelessWidget {
  const ModalBranchDecor({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: Stack(
        children: [
          // Top-right branch
          Positioned(
            top: -size.height * 0.01,
            right: -size.width * 0.08,
            child: Opacity(
              opacity: 0.72,
              child: Image.asset(
                'assets/images/todayquestionscreen/right_branch1.png',
                width: size.width * 0.34,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Bottom-left branch
          Positioned(
            left: -size.width * 0.08,
            bottom: size.height * 0.02,
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/images/todayquestionscreen/left_branch1.png',
                width: size.width * 0.32,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
