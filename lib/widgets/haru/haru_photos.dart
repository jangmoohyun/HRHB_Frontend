import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/text.dart';
import '../../theme/tokens.dart';
import 'pressable.dart';

class PhotoItem {
  const PhotoItem({
    required this.url,
    this.id,
    this.date,
    this.who,
    this.caption,
    this.tint = HaruColors.mint,
  });

  final String url;

  /// Album photo id (for delete). null for answer photos.
  final int? id;
  final String? date;
  final String? who;
  final String? caption;
  final Color tint;
}

/// Network image over the prototype's tinted placeholder (`image` icon on a
/// pastel tile) while loading or when it fails.
class HaruNetImage extends StatelessWidget {
  const HaruNetImage({
    super.key,
    required this.url,
    this.tint = HaruColors.mint,
    this.fit = BoxFit.cover,
    this.iconSize = 22,
  });

  final String url;
  final Color tint;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: tint,
      child: Center(
        child: Icon(Symbols.image_rounded, size: iconSize, color: HaruColors.softGreen),
      ),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Floating bar shown in album selection mode.
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
    Widget action(String label, Color fg, Color bg, VoidCallback? onTap) => Pressable(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(HaruRadius.full)),
              alignment: Alignment.center,
              child: Text(label, style: hr(15, color: fg)),
            ),
          ),
        );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: HaruMotion.out,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
        decoration: BoxDecoration(
          color: HaruColors.forest,
          borderRadius: BorderRadius.circular(HaruRadius.md),
          boxShadow: HaruShadows.shadow2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                none ? '사진을 골라 주세요' : '$count장 골랐어요',
                style: hr(15, color: Colors.white),
              ),
            ),
            action('저장', HaruColors.forest, HaruColors.ivory, none || busy ? null : onSave),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              action('삭제', Colors.white, HaruColors.danger, none || busy ? null : onDelete),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen photo viewer (cream, counter, save, optional delete).
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
          final c = CurvedAnimation(parent: anim, curve: HaruMotion.out);
          return FadeTransition(
            opacity: c,
            child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(c), child: child),
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
    Widget iconButton(IconData icon, String label, VoidCallback onTap) => Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 24, color: HaruColors.forest)),
        );
    return Scaffold(
      backgroundColor: HaruColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  iconButton(Symbols.close_rounded, '닫기', () => Navigator.of(context).pop()),
                  Expanded(
                    child: Text(
                      '${_index + 1} / ${widget.items.length}',
                      textAlign: TextAlign.center,
                      style: hr(17, color: HaruColors.forest),
                    ),
                  ),
                  iconButton(Symbols.download_rounded, '저장', () => widget.onSave(item)),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(HaruRadius.lg),
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: HaruNetImage(
                          url: widget.items[i].url,
                          tint: widget.items[i].tint,
                          fit: BoxFit.contain,
                          iconSize: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(item.who ?? '', style: hrHand(18)),
                      const SizedBox(width: 8),
                      Text(item.date ?? '', style: hr(13.5, color: HaruColors.inkMuted)),
                    ],
                  ),
                  if ((item.caption ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.caption!, style: hrQuestion(17, height: 1.4)),
                  ],
                  if (widget.onDelete != null) ...[
                    const SizedBox(height: 14),
                    Pressable(
                      onTap: () async {
                        final deleted = await widget.onDelete!(item);
                        if (deleted && context.mounted) Navigator.of(context).pop();
                      },
                      child: SizedBox(
                        height: 36,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Symbols.delete_rounded, size: 18, color: HaruColors.danger),
                            const SizedBox(width: 6),
                            Text('이 사진 삭제', style: hr(15, color: HaruColors.danger)),
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
