import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';
import 'album_detail_screen.dart';

/// 17 앨범 탭 (VER2: 앨범만; 답변 사진은 기록 > 사진).
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final _api = ApiClient();
  final _albums = <FamilyAlbumResult>[];
  int _next = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page = await AuthedCall.run((t) => _api.fetchFamilyAlbums(t, page: 0, size: 10));
      _albums
        ..clear()
        ..addAll(page.albums);
      _next = 1;
      _hasMore = page.hasMore;
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _more() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final page = await AuthedCall.run((t) => _api.fetchFamilyAlbums(t, page: _next, size: 10));
      _albums.addAll(page.albums);
      _next++;
      _hasMore = page.hasMore;
      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _create() async {
    final name = await showHaruInputDialog(
      context,
      title: '새 앨범',
      body: '졸업식, 생일, 여행처럼 이름을 붙여 주세요.',
      hint: '앨범 이름',
      confirmLabel: '만들기',
    );
    if (name == null || !mounted) return;
    try {
      final album = await AuthedCall.run((t) => _api.createFamilyAlbum(accessToken: t, name: name));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AlbumDetailScreen(albumId: album.albumId, title: album.title),
        ),
      );
      if (mounted) _load();
    } catch (_) {
      if (!mounted) return;
      HaruToast.show(
        context,
        '앨범을 만들지 못했어요',
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
      );
    }
  }

  Future<void> _open(FamilyAlbumResult a) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlbumDetailScreen(albumId: a.albumId, title: a.title)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 400) _more();
            return false;
          },
          child: RefreshIndicator(
            color: HaruColors.primary,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: kTabBarClearance),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text('앨범', style: HaruType.screenTitle),
                ),
                if (_loading)
                  const HaruSkeleton()
                else if (_error)
                  HaruErrorState(onRetry: _load)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '우리 가족 앨범',
                                    style: haruText(17, weight: FontWeight.w700, color: HaruColors.dsInk),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '가족 이벤트별로 사진을 모아 두어요',
                                    style: haruText(14, color: HaruColors.dsInkMuted),
                                  ),
                                ],
                              ),
                            ),
                            HaruButton(
                              label: '새 앨범',
                              icon: LucideIcons.plus,
                              variant: HaruButtonVariant.utility,
                              onPressed: _create,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_albums.isEmpty)
                          HaruOutlineCard(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: HaruEmptyState(
                              icon: LucideIcons.folderHeart,
                              title: '아직 앨범이 없어요',
                              description: '졸업식, 생일, 여행처럼\n가족 이벤트별로 사진을 모아 보세요.',
                              tint: HaruColors.accentButter,
                              padding: EdgeInsets.zero,
                              action: HaruButton(label: '앨범 만들기', onPressed: _create),
                            ),
                          )
                        else ...[
                          LayoutBuilder(builder: (_, c) {
                            final w = (c.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < _albums.length; i++)
                                  SizedBox(width: w, child: _AlbumCard(album: _albums[i], index: i, onTap: () => _open(_albums[i]))),
                              ],
                            );
                          }),
                          if (!_hasMore)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '모든 앨범을 불러왔어요',
                                textAlign: TextAlign.center,
                                style: haruText(13, color: HaruColors.dsInkFaint),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.index, required this.onTap});

  final FamilyAlbumResult album;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = HaruColors.tints[index % HaruColors.tints.length];
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: HaruOutlineCard(
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (album.coverUrl != null && album.coverUrl!.isNotEmpty)
                    HaruNetImage(url: album.coverUrl!, tint: tint)
                  else
                    ColoredBox(
                      color: tint,
                      child: const Center(
                        child: Icon(LucideIcons.images, size: 28, color: HaruColors.dsInkSecondary),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HaruColors.surface,
                        borderRadius: BorderRadius.circular(HaruRadius.full),
                      ),
                      child: Text(
                        '${album.count}',
                        style: haruText(12, weight: FontWeight.w600, color: HaruColors.dsInk, height: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: haruText(15, weight: FontWeight.w600, color: HaruColors.dsInk),
                  ),
                  const SizedBox(height: 2),
                  Text(album.dateLabel, style: haruText(13, color: HaruColors.dsInkFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
