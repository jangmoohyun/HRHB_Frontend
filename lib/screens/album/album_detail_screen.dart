import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/services/media_save_service.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';
import 'package:hrhb_frontend/widgets/haru/pressable.dart';

import '../shell/home_shell.dart';

/// 앨범 상세 — 사진 올리기 (max 20), 고르기 → 저장/삭제, 이름 바꾸기, 앨범 삭제.
class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({super.key, required this.albumId, required this.title, this.dateLabel});

  final int albumId;
  final String title;
  final String? dateLabel;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  static const _maxUpload = 20;
  static const _pageSize = 21;

  final _api = ApiClient();
  final _picker = ImagePicker();
  final _photos = <FamilyAlbumPhotoResult>[];
  late String _title = widget.title;
  int _total = 0;
  int _next = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;

  (int done, int total)? _upload;
  bool _selecting = false;
  final _sel = <int>{};
  bool _busy = false;

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
      final d = await AuthedCall.run(
        (t) => _api.fetchFamilyAlbumDetail(accessToken: t, albumId: widget.albumId, page: 0, size: _pageSize),
      );
      _photos
        ..clear()
        ..addAll(d.photos);
      _title = d.title;
      _total = d.totalCount;
      _hasMore = d.hasMore;
      _next = 1;
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _more() async {
    if (_loadingMore || !_hasMore || _loading) return;
    _loadingMore = true;
    try {
      final d = await AuthedCall.run(
        (t) => _api.fetchFamilyAlbumDetail(accessToken: t, albumId: widget.albumId, page: _next, size: _pageSize),
      );
      _photos.addAll(d.photos);
      _hasMore = d.hasMore;
      _next++;
      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      _loadingMore = false;
    }
  }

  String _contentTypeFor(XFile f) {
    final mime = f.mimeType?.toLowerCase();
    if (mime == 'image/png' || mime == 'image/jpeg' || mime == 'image/webp') return mime!;
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _uploadPhotos() async {
    if (_upload != null) return;
    final files = await _picker.pickMultiImage(limit: _maxUpload);
    if (files.isEmpty || !mounted) return;
    final picked = files.take(_maxUpload).toList();
    if (files.length > _maxUpload) HaruToast.show(context, '한 번에 20장까지 올릴 수 있어요.');
    setState(() {
      _selecting = false;
      _sel.clear();
      _upload = (0, picked.length);
    });
    try {
      final keys = <String>[];
      for (final f in picked) {
        final type = _contentTypeFor(f);
        final bytes = await f.readAsBytes();
        final key = await AuthedCall.run((t) async {
          final up = await _api.createAlbumPhotoUploadUrl(accessToken: t, albumId: widget.albumId, contentType: type);
          await _api.uploadBytesToPresignedUrl(uploadUrl: up.uploadUrl, bytes: bytes, contentType: up.contentType);
          return up.imageKey;
        });
        keys.add(key);
        if (!mounted) return;
        setState(() => _upload = (keys.length, picked.length));
      }
      await AuthedCall.run((t) => _api.addAlbumPhotos(accessToken: t, albumId: widget.albumId, imageKeys: keys));
      if (!mounted) return;
      setState(() => _upload = null);
      await _load();
      if (!mounted) return;
      HaruToast.show(context, '사진 ${keys.length}장을 올렸어요.');
      HomeShellScope.maybeOf(context)?.notifyDataChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _upload = null);
      HaruToast.show(context, '사진을 올리지 못했어요.');
    }
  }

  Future<void> _save(List<String> urls) async {
    try {
      await const MediaSaveService().saveImageUrls(urls);
      if (mounted) HaruToast.show(context, urls.length == 1 ? '사진을 저장했어요.' : '사진 ${urls.length}장을 저장했어요.');
    } catch (e) {
      if (mounted) HaruToast.show(context, e is StateError ? e.message : '사진을 저장하지 못했어요.');
    }
  }

  Future<void> _saveSelected() async {
    setState(() => _busy = true);
    await _save([for (final i in _sel) _photos[i].imageUrl]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selecting = false;
      _sel.clear();
    });
  }

  Future<bool> _deletePhotos(List<int> indexes) async {
    final ok = await showHaruConfirm(
      context,
      title: '사진 ${indexes.length}장을 지울까요?',
      body: '지운 사진은 가족 모두의 앨범에서 사라져요.',
      okLabel: '지우기',
    );
    if (!ok || !mounted) return false;
    try {
      final ids = [for (final i in indexes) _photos[i].photoId];
      await AuthedCall.run((t) => _api.deleteAlbumPhotos(accessToken: t, albumId: widget.albumId, photoIds: ids));
      if (!mounted) return true;
      setState(() {
        _selecting = false;
        _sel.clear();
      });
      await _load();
      if (mounted) HaruToast.show(context, '사진 ${ids.length}장을 지웠어요.');
      return true;
    } catch (_) {
      if (mounted) HaruToast.show(context, '사진을 지우지 못했어요.');
      return false;
    }
  }

  Future<void> _rename() async {
    final name = await showHaruInputDialog(
      context,
      title: '앨범 이름 바꾸기',
      placeholder: '앨범 이름을 입력해주세요',
      okLabel: '저장',
      initial: _title,
    );
    if (name == null || !mounted) return;
    try {
      final a = await AuthedCall.run((t) => _api.renameFamilyAlbum(accessToken: t, albumId: widget.albumId, name: name));
      if (!mounted) return;
      setState(() => _title = a.title);
      HaruToast.show(context, '앨범 이름을 바꿨어요.');
    } catch (_) {
      if (mounted) HaruToast.show(context, '이름을 바꾸지 못했어요.');
    }
  }

  Future<void> _deleteAlbum() async {
    final ok = await showHaruConfirm(
      context,
      title: '앨범을 지울까요?',
      body: '앨범 안의 사진 $_total장도 함께 지워져요.',
      okLabel: '지우기',
    );
    if (!ok || !mounted) return;
    try {
      await AuthedCall.run((t) => _api.deleteFamilyAlbum(accessToken: t, albumId: widget.albumId));
      if (!mounted) return;
      Navigator.of(context).pop();
      HaruToast.show(context, '앨범을 지웠어요.');
    } catch (_) {
      if (mounted) HaruToast.show(context, '앨범을 지우지 못했어요.');
    }
  }

  Future<void> _openMenu() async {
    final choice = await showHaruSheet<String>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(_title),
          const SizedBox(height: 10),
          HrCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                MenuRow(
                  icon: Symbols.check_circle_rounded,
                  label: '사진 고르기',
                  onTap: () => Navigator.of(ctx).pop('select'),
                ),
                MenuRow(
                  icon: Symbols.edit_rounded,
                  label: '앨범 이름 바꾸기',
                  onTap: () => Navigator.of(ctx).pop('rename'),
                ),
                MenuRow(
                  icon: Symbols.delete_rounded,
                  label: '앨범 지우기',
                  color: HaruColors.danger,
                  iconColor: HaruColors.danger,
                  chevron: false,
                  last: true,
                  onTap: () => Navigator.of(ctx).pop('delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'select':
        setState(() => _selecting = true);
      case 'rename':
        await _rename();
      case 'delete':
        await _deleteAlbum();
    }
  }

  Future<void> _openViewer(int i) => PhotoViewerPage.open(
        context,
        items: [
          for (var k = 0; k < _photos.length; k++)
            PhotoItem(
              url: _photos[k].imageUrl,
              id: _photos[k].photoId,
              date: '${_photos[k].savedAt.month}/${_photos[k].savedAt.day}',
              who: _title,
              tint: HaruColors.tints[k % HaruColors.tints.length],
            ),
        ],
        index: i,
        onSave: (item) => _save([item.url]),
        onDelete: (item) async {
          final idx = _photos.indexWhere((p) => p.photoId == item.id);
          if (idx < 0) return false;
          return _deletePhotos([idx]);
        },
      );

  void _tapPhoto(int i) {
    if (_selecting) {
      setState(() => _sel.contains(i) ? _sel.remove(i) : _sel.add(i));
    } else {
      _openViewer(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final up = _upload;
    return EdgeSwipeBack(
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
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
                padding: EdgeInsets.fromLTRB(16, 0, 16, kNavClearance + (_selecting ? 60 : 0)),
                children: [
                  SubHeader(
                    title: _title,
                    trailing: Pressable(
                      onTap: _selecting
                          ? () => setState(() {
                                _selecting = false;
                                _sel.clear();
                              })
                          : _openMenu,
                      semanticLabel: _selecting ? '고르기 끝내기' : '앨범 메뉴',
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: _selecting
                            ? Center(child: Text('완료', style: hr(15, color: HaruColors.forest)))
                            : const Icon(Symbols.more_horiz_rounded, size: 24, color: HaruColors.forest),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '사진 $_total장${(widget.dateLabel ?? '').isEmpty ? '' : ' · ${widget.dateLabel}'}',
                            style: hr(14, color: HaruColors.inkMuted),
                          ),
                        ),
                        Pressable(
                          onTap: _uploadPhotos,
                          scale: .96,
                          duration: Duration.zero,
                          inlineTransition: false,
                          semanticLabel: '사진 올리기',
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                            decoration: BoxDecoration(
                              color: HaruColors.cta,
                              borderRadius: BorderRadius.circular(HaruRadius.full),
                              boxShadow: HaruShadows.shadow3,
                            ),
                            child: Row(
                              children: [
                                const Icon(Symbols.add_photo_alternate_rounded, size: 18, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  up == null ? '사진 올리기' : '올리는 중 ${up.$1}/${up.$2}',
                                  style: hr(15, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error)
                    _message('사진을 불러오지 못했어요.\n눌러서 다시 시도해 주세요.', onTap: _load)
                  else if (!_loading && _photos.isEmpty)
                    _message('아직 사진이 없어요.\n첫 사진을 올려 보세요.')
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = (c.maxWidth - 8) / 3;
                        return Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (var i = 0; i < _photos.length; i++)
                              Entrance(
                                key: ValueKey(_photos[i].photoId),
                                kind: EntranceKind.pop,
                                delay: stagger(i % _pageSize, 25),
                                child: GestureDetector(
                                  onTap: () => _tapPhoto(i),
                                  onLongPress: () => setState(() {
                                    _selecting = true;
                                    _sel.add(i);
                                  }),
                                  child: SizedBox(
                                    width: w,
                                    height: w,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: HaruNetImage(
                                            url: _photos[i].imageUrl,
                                            tint: HaruColors.tints[i % HaruColors.tints.length],
                                          ),
                                        ),
                                        if (_selecting) _SelectMark(selected: _sel.contains(i)),
                                      ],
                                    ),
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
          ),
          if (_selecting)
            Positioned(
              left: 20,
              right: 20,
              bottom: 98,
              child: SelectionBar(
                count: _sel.length,
                busy: _busy,
                onSave: _saveSelected,
                onDelete: () => _deletePhotos(_sel.toList()..sort()),
              ),
            ),
        ],
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

class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (selected)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HaruColors.cta, width: 3),
            ),
            child: const SizedBox.expand(),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: selected ? HaruColors.cta : const Color(0x33000000),
            ),
            child: selected ? const Icon(Symbols.check_rounded, size: 14, color: Colors.white) : null,
          ),
        ),
      ],
    );
  }
}
