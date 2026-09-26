import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:hrhb_frontend/data/authed_call.dart';
import 'package:hrhb_frontend/services/api_client.dart';
import 'package:hrhb_frontend/theme/text.dart';
import 'package:hrhb_frontend/theme/tokens.dart';
import 'package:hrhb_frontend/widgets/haru/haru_button.dart';
import 'package:hrhb_frontend/widgets/haru/haru_layout.dart';
import 'package:hrhb_frontend/widgets/haru/haru_overlays.dart';
import 'package:hrhb_frontend/widgets/haru/haru_photos.dart';

import '../archive/answer_photos_screen.dart' show saveToDevice;
import '../shell/home_shell.dart';

/// 20 앨범 상세 — upload (max 20), select/save/delete, rename, delete album.
class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({super.key, required this.albumId, required this.title});

  final int albumId;
  final String title;

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
    if (_loadingMore || !_hasMore) return;
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

  void _toastError(String msg) => HaruToast.show(
        context,
        msg,
        icon: LucideIcons.circleAlert,
        iconColor: HaruColors.statusAttention,
      );

  Future<void> _uploadPhotos() async {
    if (_upload != null) return;
    final files = await _picker.pickMultiImage(limit: _maxUpload);
    if (files.isEmpty || !mounted) return;
    final picked = files.take(_maxUpload).toList();
    if (files.length > _maxUpload) HaruToast.show(context, '한 번에 20장까지 올릴 수 있어요');
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
      if (mounted) HaruToast.show(context, '${keys.length}장을 올렸어요');
    } catch (_) {
      if (!mounted) return;
      setState(() => _upload = null);
      _toastError('사진을 올리지 못했어요');
    }
  }

  Future<void> _saveSelected() async {
    setState(() => _busy = true);
    await saveToDevice(context, [for (final i in _sel) _photos[i].imageUrl]);
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
      title: '사진 ${indexes.length}장을 삭제할까요?',
      body: '삭제한 사진은 가족 모두의 앨범에서 사라져요.',
      confirmLabel: '삭제',
      danger: true,
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
      if (mounted) HaruToast.show(context, '${ids.length}장을 삭제했어요');
      return true;
    } catch (_) {
      if (mounted) _toastError('사진을 삭제하지 못했어요');
      return false;
    }
  }

  Future<void> _rename() async {
    final name = await showHaruInputDialog(
      context,
      title: '앨범 이름 바꾸기',
      initialValue: _title,
      hint: '앨범 이름',
      confirmLabel: '저장',
    );
    if (name == null || !mounted) return;
    try {
      final a = await AuthedCall.run((t) => _api.renameFamilyAlbum(accessToken: t, albumId: widget.albumId, name: name));
      if (!mounted) return;
      setState(() => _title = a.title);
      HaruToast.show(context, '앨범 이름을 바꿨어요');
    } catch (_) {
      if (mounted) _toastError('이름을 바꾸지 못했어요');
    }
  }

  Future<void> _deleteAlbum() async {
    final ok = await showHaruConfirm(
      context,
      title: '앨범을 삭제할까요?',
      body: '앨범 안의 사진 $_total장도 함께 삭제돼요.',
      confirmLabel: '삭제',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await AuthedCall.run((t) => _api.deleteFamilyAlbum(accessToken: t, albumId: widget.albumId));
      if (!mounted) return;
      Navigator.of(context).pop();
      HaruToast.show(context, '앨범을 삭제했어요');
    } catch (_) {
      if (mounted) _toastError('앨범을 삭제하지 못했어요');
    }
  }

  Future<void> _openMenu() async {
    final choice = await showGeneralDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) {
        final top = MediaQuery.paddingOf(ctx).top + 56;
        Widget item(String value, IconData icon, String label, {Color? color}) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(value),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color ?? HaruColors.dsInk),
                    const SizedBox(width: 10),
                    Text(label, style: haruText(15, color: color ?? HaruColors.dsInk)),
                  ],
                ),
              ),
            );
        return Stack(
          children: [
            Positioned(
              top: top,
              right: 16,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 168),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: HaruColors.surface,
                    borderRadius: BorderRadius.circular(HaruRadius.md),
                    boxShadow: HaruShadows.s2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      item('select', LucideIcons.circleCheck, '사진 선택'),
                      item('rename', LucideIcons.pencil, '이름 바꾸기'),
                      item('delete', LucideIcons.trash2, '앨범 삭제', color: HaruColors.statusAttention),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: HaruMotion.standard);
        return FadeTransition(
          opacity: c,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween(begin: 0.92, end: 1.0).animate(c),
            child: child,
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'select':
        // Same item toggles selection mode off again (prototype toggleSelect).
        setState(() {
          _selecting = !_selecting;
          _sel.clear();
        });
      case 'rename':
        await _rename();
      case 'delete':
        await _deleteAlbum();
    }
  }

  List<PhotoItem> get _items => [
        for (var i = 0; i < _photos.length; i++)
          PhotoItem(
            url: _photos[i].imageUrl,
            id: _photos[i].photoId,
            who: _title,
            date: '${_photos[i].savedAt.year}.${_photos[i].savedAt.month.toString().padLeft(2, '0')}.${_photos[i].savedAt.day.toString().padLeft(2, '0')}',
            fallbackTint: HaruColors.tints[i % HaruColors.tints.length],
          ),
      ];

  void _tap(int i) {
    if (_selecting) {
      setState(() => _sel.contains(i) ? _sel.remove(i) : _sel.add(i));
      return;
    }
    final items = _items;
    PhotoViewerPage.open(
      context,
      items: items,
      index: i,
      onSave: (item) => saveToDevice(context, [item.url]),
      onDelete: (item) => _deletePhotos([items.indexOf(item)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final up = _upload;
    return Scaffold(
      backgroundColor: HaruColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                HaruSubHeader(
                  title: _title,
                  trailing: [
                    HaruIconButton(icon: LucideIcons.imagePlus, label: '사진 올리기', onPressed: _uploadPhotos),
                    HaruIconButton(
                      icon: LucideIcons.ellipsisVertical,
                      label: '더보기',
                      onPressed: _openMenu,
                    ),
                  ],
                ),
                if (up != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: HaruOutlineCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '사진을 올리고 있어요',
                                  style: haruText(14, weight: FontWeight.w600, color: HaruColors.dsInk),
                                ),
                              ),
                              Text('${up.$1} / ${up.$2}', style: haruText(14, color: HaruColors.dsInkMuted)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(HaruRadius.full),
                            child: SizedBox(
                              height: 6,
                              child: Stack(
                                children: [
                                  const Positioned.fill(child: ColoredBox(color: HaruColors.fillTranslucent)),
                                  AnimatedFractionallySizedBox(
                                    duration: const Duration(milliseconds: 300),
                                    widthFactor: up.$2 == 0 ? 0 : up.$1 / up.$2,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: HaruColors.primary,
                                        borderRadius: BorderRadius.circular(HaruRadius.full),
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
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: HaruColors.primary))
                      : _error
                          ? HaruErrorState(onRetry: _load)
                          : _photos.isEmpty && up == null
                              ? HaruEmptyState(
                                  icon: LucideIcons.images,
                                  title: '아직 사진이 없어요',
                                  titleSize: 17,
                                  description: '한 번에 20장까지 올릴 수 있어요.',
                                  tint: HaruColors.accentSky,
                                  tileSize: 56,
                                  iconSize: 26,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
                                  action: HaruButton(label: '사진 올리기', onPressed: _uploadPhotos),
                                )
                              : NotificationListener<ScrollNotification>(
                                  onNotification: (n) {
                                    if (n.metrics.extentAfter < 400) _more();
                                    return false;
                                  },
                                  child: RefreshIndicator(
                                    color: HaruColors.primary,
                                    onRefresh: _load,
                                    child: ListView(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      padding: EdgeInsets.fromLTRB(16, 0, 16, kTabBarClearance + (_selecting ? 80 : 0)),
                                      children: [
                                        PhotoGrid(
                                          items: _items,
                                          onTap: _tap,
                                          selecting: _selecting,
                                          selected: _sel,
                                          gap: 3,
                                          radius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                ),
              ],
            ),
            if (_selecting)
              Positioned(
                left: 12,
                right: 12,
                bottom: 92,
                child: SelectionBar(
                  count: _sel.length,
                  busy: _busy,
                  onSave: _saveSelected,
                  onDelete: () => _deletePhotos(_sel.toList()..sort()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
