import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'haru_button.dart';

class PhotoItem {
  const PhotoItem({
    required this.url,
    this.id,
    this.date,
    this.who,
    this.caption,
    this.fallbackTint = HaruColors.accentSky,
  });

  final String url;

  /// Album photo id (for delete). null for answer photos.
  final int? id;
  final String? date;
  final String? who;
  final String? caption;
  final Color fallbackTint;
}

/// Network image with the prototype's tinted placeholder while loading/failing.
class HaruNetImage extends StatelessWidget {
  const HaruNetImage({super.key, required this.url, required this.tint, this.fit = BoxFit.cover});

  final String url;
  final Color tint;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : ColoredBox(color: tint),
      errorBuilder: (_, _, _) => ColoredBox(
        color: tint,
        child: const Center(
          child: Icon(LucideIcons.image, size: 24, color: HaruColors.dsInkSecondary),
        ),
      ),
    );
  }
}

/// Square photo grid (3 columns) with optional captions and selection marks.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.selecting = false,
    this.selected = const {},
    this.captions = false,
    this.gap = 8,
    this.radius = 8,
    this.captionStyleVer2 = false,
  });

  final List<PhotoItem> items;
  final ValueChanged<int> onTap;
  final bool selecting;
  final Set<int> selected;
  final bool captions;
  final double gap;
  final double radius;

  /// 기록 > 사진 uses the VER2 caption colors.
  final bool captionStyleVer2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: captions ? 0 : gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: w,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: Column(
                    children: [
                      SizedBox(
                        width: w,
                        height: w,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(radius),
                              child: HaruNetImage(url: items[i].url, tint: items[i].fallbackTint),
                            ),
                            if (selecting && selected.contains(i))
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(radius),
                                  border: Border.all(color: HaruColors.primary, width: 3),
                                ),
                              ),
                            if (selecting)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    color: selected.contains(i)
                                        ? HaruColors.primary
                                        : const Color(0x2E000000),
                                  ),
                                  child: selected.contains(i)
                                      ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (captions)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Column(
                            children: [
                              Text(
                                items[i].date ?? '',
                                style: haruText(
                                  12,
                                  color: captionStyleVer2
                                      ? HaruColors.inkSecondary
                                      : HaruColors.dsInkFaint,
                                ),
                              ),
                              Text(
                                items[i].who ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: haruText(
                                  12,
                                  weight: captionStyleVer2 ? FontWeight.w600 : FontWeight.w500,
                                  color: captionStyleVer2
                                      ? HaruColors.ink
                                      : HaruColors.dsInkSecondary,
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
        );
      },
    );
  }
}

/// Floating bar shown in selection mode (bottom 92px, above the tab bar).
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onSave,
    this.onDelete,
    this.busy = false,
  });

  final int count;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final none = count == 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: HaruMotion.standard,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
        decoration: BoxDecoration(
          color: HaruColors.surface,
          borderRadius: BorderRadius.circular(HaruRadius.lg),
          boxShadow: HaruShadows.s2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                none ? '사진을 선택하세요' : '$count장 선택됨',
                style: haruText(15, weight: FontWeight.w600, color: HaruColors.dsInk),
              ),
            ),
            HaruButton(
              label: '저장',
              icon: LucideIcons.download,
              variant: HaruButtonVariant.secondary,
              loading: busy,
              onPressed: none ? null : onSave,
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: none ? null : onDelete,
                child: Opacity(
                  opacity: none ? 0.4 : 1,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Text(
                      '삭제',
                      style: haruText(16, weight: FontWeight.w500, color: HaruColors.statusAttention),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen photo viewer (canvas-soft, counter, save, optional delete).
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.onSave,
    this.onDelete,
  });

  final List<PhotoItem> items;
  final int initialIndex;
  final Future<void> Function(PhotoItem item) onSave;

  /// Album only — returns true when deleted (viewer then closes).
  final Future<bool> Function(PhotoItem item)? onDelete;

  static Future<void> open(
    BuildContext context, {
    required List<PhotoItem> items,
    required int index,
    required Future<void> Function(PhotoItem item) onSave,
    Future<bool> Function(PhotoItem item)? onDelete,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => PhotoViewerPage(
          items: items,
          initialIndex: index,
          onSave: onSave,
          onDelete: onDelete,
        ),
        transitionsBuilder: (_, anim, _, child) {
          final c = CurvedAnimation(parent: anim, curve: HaruMotion.standard);
          return FadeTransition(
            opacity: c,
            child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(c), child: child),
          );
        },
      ),
    );
  }

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final _page = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];
    return Scaffold(
      backgroundColor: HaruColors.canvasSoft,
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    HaruIconButton(
                      icon: LucideIcons.x,
                      label: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} / ${widget.items.length}',
                        textAlign: TextAlign.center,
                        style: haruText(15, weight: FontWeight.w600, color: HaruColors.dsInk),
                      ),
                    ),
                    HaruIconButton(
                      icon: LucideIcons.download,
                      label: '저장',
                      onPressed: () => widget.onSave(item),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(HaruRadius.lg),
                        child: InteractiveViewer(
                          maxScale: 4,
                          child: HaruNetImage(
                            url: widget.items[i].url,
                            tint: widget.items[i].fallbackTint,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(item.who ?? '', style: haruText(15, weight: FontWeight.w600, color: HaruColors.dsInk)),
                      const SizedBox(width: 8),
                      Text(item.date ?? '', style: haruText(13, color: HaruColors.dsInkFaint)),
                    ],
                  ),
                  if ((item.caption ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.caption!, style: haruText(14, height: 1.5, color: HaruColors.dsInkMuted)),
                  ],
                  if (widget.onDelete != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final deleted = await widget.onDelete!(item);
                        if (deleted && context.mounted) Navigator.of(context).pop();
                      },
                      child: SizedBox(
                        height: 36,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.trash2, size: 16, color: HaruColors.statusAttention),
                            const SizedBox(width: 6),
                            Text('이 사진 삭제', style: haruText(15, color: HaruColors.statusAttention)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical ±°C bar chart (최근 6일간의 변화, 리포트 온도 변화).
class TempBarChart extends StatelessWidget {
  const TempBarChart({super.key, required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 70,
                child: SizedBox(height: 1, child: ColoredBox(color: HaruColors.inputBorder)),
              ),
              Row(
                children: [
                  for (final v in values)
                    Expanded(
                      child: LayoutBuilder(builder: (_, c) {
                        final h = (v.abs() * 56).clamp(3, 140).toDouble();
                        final top = v > 0 ? 70 - h : v < 0 ? 70.0 : 68.5;
                        final label = v == 0
                            ? '0'
                            : '${v > 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)}';
                        final labelTop = v >= 0 ? top - 18 : top + h + 4;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: c.maxWidth / 2 - 14,
                              top: top,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 600),
                                curve: HaruMotion.standard,
                                builder: (_, t, _) => Container(
                                  width: 28,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: (v > 0
                                            ? HaruColors.accentOrange
                                            : v < 0
                                                ? HaruColors.accentSky
                                                : HaruColors.inputBorder)
                                        .withValues(alpha: t),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: labelTop,
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: haruText(12, weight: FontWeight.w600, color: HaruColors.dsInkSecondary, height: 1.2),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: haruText(12, color: HaruColors.dsInkFaint),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
