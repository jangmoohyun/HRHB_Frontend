import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';
import 'album_detail_screen.dart';

/// 앨범 탭 — 가족 이벤트별 앨범.
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
    if (_loadingMore || !_hasMore || _loading) return;
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
      title: '새 앨범 만들기',
      placeholder: '앨범 이름을 입력해주세요',
      okLabel: '만들기',
      reject: (n) => _albums.any((a) => a.title == n) ? '이미 같은 이름의 앨범이 있어요.' : null,
    );
    if (name == null || !mounted) return;
    try {
      final album = await AuthedCall.run((t) => _api.createFamilyAlbum(accessToken: t, name: name));
      if (!mounted) return;
      HaruToast.show(context, '‘$name’ 앨범을 만들었어요.');
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AlbumDetailScreen(
            albumId: album.albumId,
            title: album.title,
            dateLabel: album.dateLabel,
          ),
        ),
      );
      if (mounted) _load();
    } catch (_) {
      if (mounted) HaruToast.show(context, '앨범을 만들지 못했어요.');
    }
  }

  Future<void> _open(FamilyAlbumResult a) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AlbumDetailScreen(albumId: a.albumId, title: a.title, dateLabel: a.dateLabel),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) _more();
        return false;
      },
      child: RefreshIndicator(
        color: HaruColors.forest,
        backgroundColor: HaruColors.ivory,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, kNavClearance),
          children: [
            Entrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabHeader(title: '우리 가족 앨범'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text('가족 이벤트별로 사진을 모아 두어요', style: hr(14, color: HaruColors.inkMuted)),
                      ),
                      Pressable(
                        onTap: _create,
                        semanticLabel: '새 앨범',
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                          decoration: BoxDecoration(
                            color: HaruColors.mint,
                            borderRadius: BorderRadius.circular(HaruRadius.full),
                          ),
                          child: Row(
                            children: [
                              const Icon(Symbols.add_rounded, size: 20, color: HaruColors.forest),
                              const SizedBox(width: 2),
                              Text('새 앨범', style: hr(15, color: HaruColors.forest)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error)
                    _message('앨범을 불러오지 못했어요.\n눌러서 다시 시도해 주세요.', onTap: _load)
                  else if (!_loading && _albums.isEmpty)
                    _message('아직 앨범이 없어요.\n‘새 앨범’으로 첫 앨범을 만들어 보세요.')
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = (c.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var i = 0; i < _albums.length; i++)
                              SizedBox(
                                width: w,
                                child: Entrance(
                                  key: ValueKey(_albums[i].albumId),
                                  kind: EntranceKind.pop,
                                  duration: const Duration(milliseconds: 500),
                                  delay: stagger(i % 10, 60),
                                  child: _AlbumCard(
                                    album: _albums[i],
                                    tint: HaruColors.tints[i % 4],
                                    onTap: () => _open(_albums[i]),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Pressable(
            onTap: onTap,
            child: Text(text, textAlign: TextAlign.center, style: hr(15, color: HaruColors.inkMuted, height: 1.6)),
          ),
        ),
      );
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.tint, required this.onTap});

  final FamilyAlbumResult album;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: album.title,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HaruColors.ivory,
          border: Border.all(color: HaruColors.hairline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HaruNetImage(url: album.coverUrl ?? '', tint: tint, iconSize: 34),
                  if (album.coverUrl == null || album.coverUrl!.isEmpty)
                    ColoredBox(
                      color: tint,
                      child: const Icon(Symbols.photo_library_rounded, size: 34, color: HaruColors.softGreen),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xE03A6A3F),
                        borderRadius: BorderRadius.circular(HaruRadius.full),
                      ),
                      alignment: Alignment.center,
                      child: Text('${album.count}', style: hr(14.5, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: hr(16)),
                  const SizedBox(height: 2),
                  Text(album.dateLabel, style: hr(13.5, color: HaruColors.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
