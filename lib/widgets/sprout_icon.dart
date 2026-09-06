import 'package:flutter/material.dart';

/// Shared sprout asset used across the app.
const kSproutAsset = 'assets/images/public/sprout.png';

const _lineGrey = Color(0xFFD8D8D8);

class SproutIcon extends StatelessWidget {
  const SproutIcon({
    super.key,
    required this.size,
    this.opacity = 1,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      kSproutAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (opacity >= 1) return image;
    return Opacity(opacity: opacity.clamp(0, 1), child: image);
  }
}

class SproutDivider extends StatelessWidget {
  const SproutDivider({super.key, this.width = 168, this.iconSize = 12});

  final double width;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: _lineGrey),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SproutIcon(size: iconSize),
          ),
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: _lineGrey),
          ),
        ],
      ),
    );
  }
}
